package controller

import (
	"context"
	"fmt"
	"time"

	"github.com/mbhatt/tvm/pkg/apis/vvm/v1alpha1"
	"github.com/mbhatt/tvm/pkg/flintlock"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/tools/record"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var log = logf.Log.WithName("controller_microvm")

// Add creates a new MicroVM Controller and adds it to the Manager
func Add(mgr manager.Manager, flintlockEndpoint string) error {
	return add(mgr, newReconciler(mgr, flintlockEndpoint))
}

// newReconciler returns a new reconcile.Reconciler
func newReconciler(mgr manager.Manager, flintlockEndpoint string) reconcile.Reconciler {
	flintlockClient, err := flintlock.NewClient(flintlockEndpoint)
	if err != nil {
		log.Error(err, "Failed to create Flintlock client")
		return nil
	}

	return &ReconcileMicroVM{
		client:          mgr.GetClient(),
		scheme:          mgr.GetScheme(),
		recorder:        mgr.GetEventRecorderFor("microvm-controller"),
		flintlockClient: flintlockClient,
	}
}

// add adds a new Controller to mgr with r as the reconcile.Reconciler
func add(mgr manager.Manager, r reconcile.Reconciler) error {
	// Create a new controller
	c, err := controller.New("microvm-controller", mgr, controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to MicroVM
	// Use the new API for controller-runtime v0.20.4
	err = c.Watch(
		source.Kind(
			mgr.GetCache(),
			&v1alpha1.MicroVM{},
			&handler.TypedEnqueueRequestForObject[*v1alpha1.MicroVM]{},
		),
	)
	if err != nil {
		return err
	}

	return nil
}

// ReconcileMicroVM reconciles a MicroVM object
type ReconcileMicroVM struct {
	client          client.Client
	scheme          *runtime.Scheme
	recorder        record.EventRecorder
	flintlockClient *flintlock.Client
}

// Reconcile reads that state of the cluster for a MicroVM object and makes changes based on the state read
func (r *ReconcileMicroVM) Reconcile(ctx context.Context, request reconcile.Request) (reconcile.Result, error) {
	reqLogger := log.WithValues("Request.Namespace", request.Namespace, "Request.Name", request.Name)
	reqLogger.Info("Reconciling MicroVM")

	// Fetch the MicroVM instance
	instance := &v1alpha1.MicroVM{}
	err := r.client.Get(ctx, request.NamespacedName, instance)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Return and don't requeue
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		return reconcile.Result{}, err
	}

	// Check if the MicroVM is being deleted
	if !instance.ObjectMeta.DeletionTimestamp.IsZero() {
		return r.handleDelete(ctx, instance)
	}

	// Handle different states
	switch instance.Status.State {
	case "":
		// New MicroVM, initialize it
		return r.handleNew(ctx, instance)
	case v1alpha1.MicroVMStateCreating:
		// MicroVM is being created, check its status
		return r.handleCreating(ctx, instance)
	case v1alpha1.MicroVMStateRunning:
		// MicroVM is running, update its status
		return r.handleRunning(ctx, instance)
	case v1alpha1.MicroVMStateError:
		// MicroVM is in error state, try to recover
		return r.handleError(ctx, instance)
	case v1alpha1.MicroVMStateDeleted:
		// MicroVM is deleted, clean up
		return reconcile.Result{}, nil
	default:
		// Unknown state
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = fmt.Sprintf("Unknown state: %s", instance.Status.State)
		err = r.client.Status().Update(ctx, instance)
		return reconcile.Result{}, err
	}
}

// handleNew handles a new MicroVM
func (r *ReconcileMicroVM) handleNew(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	log.Info("Handling new MicroVM", "namespace", instance.Namespace, "name", instance.Name)
	
	// Set initial state to Creating
	instance.Status.State = v1alpha1.MicroVMStateCreating
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	
	// Update the status to Creating
	err := r.client.Status().Update(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status to Creating", "namespace", instance.Namespace, "name", instance.Name)
		return reconcile.Result{}, err
	}
	
	// Create the MicroVM using Flintlock
	err = r.flintlockClient.CreateMicroVM(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to create MicroVM", "namespace", instance.Namespace, "name", instance.Name)
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = fmt.Sprintf("Failed to create MicroVM: %v", err)
	} else {
		// Update the status based on the response from Flintlock
		err = r.flintlockClient.UpdateMicroVMStatus(instance)
		if err != nil {
			log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
			instance.Status.State = v1alpha1.MicroVMStateError
			instance.Status.Error = fmt.Sprintf("Failed to update MicroVM status: %v", err)
		}
	}
	
	// Update the status
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		return reconcile.Result{}, err
	}
	
	log.Info("MicroVM status updated to Running", "namespace", instance.Namespace, "name", instance.Name)
	
	// No need to requeue, it's already in Running state
	return reconcile.Result{}, nil
}

// handleCreating handles a MicroVM that is being created
func (r *ReconcileMicroVM) handleCreating(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	log.Info("Handling MicroVM in Creating state", "namespace", instance.Namespace, "name", instance.Name)
	
	// Update the status based on the response from Flintlock
	err := r.flintlockClient.UpdateMicroVMStatus(instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = fmt.Sprintf("Failed to update MicroVM status: %v", err)
	}
	
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	
	// Update the instance status
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		return reconcile.Result{}, err
	}
	
	log.Info("MicroVM status updated to Running", "namespace", instance.Namespace, "name", instance.Name)
	
	// No need to requeue, it's already in Running state
	return reconcile.Result{}, nil
}

// handleRunning handles a running MicroVM
func (r *ReconcileMicroVM) handleRunning(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	log.Info("Handling MicroVM in Running state", "namespace", instance.Namespace, "name", instance.Name)
	
	// Update the status based on the response from Flintlock
	err := r.flintlockClient.UpdateMicroVMStatus(instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		instance.Status.State = v1alpha1.MicroVMStateError
		instance.Status.Error = fmt.Sprintf("Failed to update MicroVM status: %v", err)
	}
	
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	
	// Update the instance status
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		return reconcile.Result{}, err
	}
	
	log.Info("MicroVM status maintained as Running", "namespace", instance.Namespace, "name", instance.Name)
	
	// Requeue periodically to update status
	return reconcile.Result{RequeueAfter: 30 * time.Second}, nil
}

// handleError handles a MicroVM in error state
func (r *ReconcileMicroVM) handleError(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	log.Info("Handling MicroVM in Error state", "namespace", instance.Namespace, "name", instance.Name, "error", instance.Status.Error)
	
	// Log the error
	log.Error(fmt.Errorf(instance.Status.Error), "MicroVM in error state", "namespace", instance.Namespace, "name", instance.Name)
	
	// Try to recover by updating the status from Flintlock
	err := r.flintlockClient.UpdateMicroVMStatus(instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status during recovery", "namespace", instance.Namespace, "name", instance.Name)
		// Keep the error state but update the error message
		instance.Status.Error = fmt.Sprintf("Failed to recover: %v. Original error: %s", err, instance.Status.Error)
	} else {
		// If we successfully updated the status, clear the error message if the state is no longer Error
		if instance.Status.State != v1alpha1.MicroVMStateError {
			instance.Status.Error = ""
		}
	}
	
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	
	// Update the instance status
	err = r.client.Status().Update(ctx, instance)
	if err != nil {
		log.Error(err, "Failed to update MicroVM status", "namespace", instance.Namespace, "name", instance.Name)
		return reconcile.Result{}, err
	}
	
	log.Info("MicroVM recovered from Error state to Running", "namespace", instance.Namespace, "name", instance.Name)
	
	// No need to requeue, it's already in Running state
	return reconcile.Result{}, nil
}

// handleDelete handles a MicroVM that is being deleted
func (r *ReconcileMicroVM) handleDelete(ctx context.Context, instance *v1alpha1.MicroVM) (reconcile.Result, error) {
	// Delete the MicroVM using Flintlock
	if instance.Status.VMID != "" {
		err := r.flintlockClient.DeleteMicroVM(ctx, instance.Status.VMID)
		if err != nil {
			log.Error(err, "Failed to delete MicroVM", "namespace", instance.Namespace, "name", instance.Name)
			// Continue with deletion even if Flintlock fails
		}
	}

	// Update status to Deleted
	instance.Status.State = v1alpha1.MicroVMStateDeleted
	instance.Status.LastActivity = &metav1.Time{Time: time.Now()}
	err := r.client.Status().Update(ctx, instance)
	if err != nil && !errors.IsNotFound(err) {
		return reconcile.Result{}, err
	}

	return reconcile.Result{}, nil
}
